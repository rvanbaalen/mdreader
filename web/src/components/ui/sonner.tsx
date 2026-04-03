import { Toaster as Sonner, type ToasterProps } from "sonner"
import { CheckCircleIcon, InfoIcon, WarningIcon, XCircleIcon, SpinnerIcon } from "@phosphor-icons/react"
import { useApp } from "@/hooks/useStore"

const Toaster = ({ ...props }: ToasterProps) => {
  const { theme } = useApp()

  return (
    <Sonner
      theme={theme}
      className="toaster group"
      position="bottom-center"
      icons={{
        success: <CheckCircleIcon data-icon />,
        info: <InfoIcon data-icon />,
        warning: <WarningIcon data-icon />,
        error: <XCircleIcon data-icon />,
        loading: <SpinnerIcon className="animate-spin" data-icon />,
      }}
      toastOptions={{
        classNames: {
          toast: "bg-card border-border text-card-foreground font-sans text-sm shadow-lg rounded-xl",
        },
      }}
      {...props}
    />
  )
}

export { Toaster }
